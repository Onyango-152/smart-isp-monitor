import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';

/// SplashScreen is the first screen the user sees when the app launches.
/// It shows the logo for 2 seconds, checks if there is a saved login
/// session, then navigates to the correct screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // AnimationController drives the fade-in animation
  late AnimationController _controller;
  late Animation<double>   _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Set up a simple fade-in animation for the logo
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // After 2.5 seconds try to restore a saved session, then navigate
    Future.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.tryAutoLogin();
      if (!mounted) return;
      _navigate();
    });
  }

  void _navigate() {
    final auth = context.read<AuthProvider>();

    // If user is already logged in (has a saved session) go directly
    // to their role-specific home screen. Otherwise go to login.
    if (auth.isAuthenticated) {
      _navigateByRole(auth.userRole);
    } else {
      Navigator.of(context).pushReplacementNamed(AppConstants.loginRoute);
    }
  }

  void _navigateByRole(String role) {
    switch (role) {
      case AppConstants.roleTechnician:
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
      default:
        Navigator.of(context)
            .pushReplacementNamed(AppConstants.loginRoute);
    }
  }

  @override
  void dispose() {
    // Always dispose animation controllers to free memory
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon container
              Container(
                width:        100,
                height:       100,
                decoration:   BoxDecoration(
                  color:        AppColors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.network_check,
                  size:  56,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 28),

              // App name
              const Text(
                'ISP Monitor',
                style: TextStyle(
                  color:       AppColors.white,
                  fontSize:    32,
                  fontWeight:  FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Text(
                'Smart Network Monitoring',
                style: TextStyle(
                  color:    AppColors.white.withOpacity(0.75),
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator
              SizedBox(
                width:  24,
                height: 24,
                child:  CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}