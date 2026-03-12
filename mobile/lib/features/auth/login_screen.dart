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
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _animCtrl, curve: Curves.easeOutCubic));

    // Clear any stale error from a previous session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().clearError();
      _animCtrl.forward();
    });

    // Clear error when user starts typing
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
      // routeForRole resolves the correct shell for this user's role
      Navigator.of(context).pushReplacementNamed(auth.routeForRole);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside a field
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // No background — we paint our own gradient
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
              colors: [
                AppColors.appBarGradientStart, // deep navy
                Color(0xFF1A56DB),             // mid blue
                AppColors.background,          // light slate at bottom
              ],
              stops: [0.0, 0.35, 0.35],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      const SizedBox(height: 44),

                      // ── Logo + headline ──────────────────────────────
                      _buildHeader(),

                      const SizedBox(height: 32),

                      // ── Card containing the form ─────────────────────
                      _buildFormCard(),

                      const SizedBox(height: 20),

                      // ── Sign up link ─────────────────────────────────
                      _buildSignUpRow(),

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

  // ── Header section ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width:  76,
          height: 76,
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset:     const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.network_check_rounded,
            size:  40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ISP Monitor',
          style: TextStyle(
            fontSize:      28,
            fontWeight:    FontWeight.w800,
            color:         Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Network Operations Centre',
          style: TextStyle(
            fontSize: 13,
            color:    Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ── Form card ─────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow:    AppShadows.heroCard,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text('Sign In', style: AppTextStyles.heading1),
          const SizedBox(height: 4),
          Text(
            'Enter your credentials to continue',
            style: AppTextStyles.bodySmall,
          ),

          const SizedBox(height: 24),

          // Error message
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.errorMessage == null) return const SizedBox.shrink();
              return _buildErrorBanner(auth.errorMessage!);
            },
          ),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Username field
                _buildFieldLabel('Username or Email'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:   _usernameCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText:   'technician@isp.co.ke',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your username or email'
                      : null,
                ),

                const SizedBox(height: 18),

                // Password field
                _buildFieldLabel('Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:      _passwordCtrl,
                  obscureText:     _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    hintText:   '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Login button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => ElevatedButton(
                    onPressed: auth.isLoading ? null : () {
                      AppUtils.haptic();
                      _handleLogin();
                    },
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
              ],
            ),
          ),

          // Demo credentials hint
          const SizedBox(height: 20),
          _buildDemoHint(),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.labelBold,
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width:   double.infinity,
      margin:  const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.offlineLight,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(
            color: AppColors.offline.withOpacity(0.3)),
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
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.offline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoHint() {
    return Container(
      padding:    const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.primarySurfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(
            color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Demo Accounts',
                style: AppTextStyles.labelBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _demoRow(Icons.build_rounded,      'technician@isp.co.ke'),
          _demoRow(Icons.bar_chart_rounded,  'manager@isp.co.ke'),
          _demoRow(Icons.person_rounded,     'customer@isp.co.ke'),
          const SizedBox(height: 4),
          Text(
            'Password: password123',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _demoRow(IconData icon, String email) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: () {
              _usernameCtrl.text = email;
              _passwordCtrl.text = 'password123';
              AppUtils.hapticSelect();
            },
            child: Text(
              email,
              style: AppTextStyles.mono.copyWith(
                fontSize: 11,
                color:    AppColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account?  ",
          style: AppTextStyles.bodySmall,
        ),
        GestureDetector(
          onTap: () {
            AppUtils.hapticSelect();
            Navigator.of(context).pushNamed(AppConstants.registerRoute);
          },
          child: Text(
            'Sign Up',
            style: AppTextStyles.labelBold.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}