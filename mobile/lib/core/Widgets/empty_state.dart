import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils.dart';

/// EmptyState is shown when a list or screen has no content to display.
///
/// Every list screen uses this so the user always gets a helpful message
/// instead of a blank screen.
///
/// Features:
///   - Fade + scale entrance animation
///   - Configurable icon colour for different contexts
///     (blue = no data, red = error, amber = filtered/empty search)
///   - Primary action button (e.g. "Retry", "Add Device")
///   - Optional secondary action (e.g. "Clear Filters")
///
/// Usage:
/// ```dart
/// // No devices yet
/// EmptyState(
///   icon:        Icons.router_outlined,
///   title:       'No Devices Found',
///   message:     'Add your first device to start monitoring.',
///   actionLabel: 'Add Device',
///   onAction:    () {},
/// )
///
/// // Search returned nothing
/// EmptyState(
///   icon:               Icons.search_off_rounded,
///   title:              'No Results',
///   message:            'No devices match your search.',
///   color:              AppColors.degraded,
///   actionLabel:        'Clear Filters',
///   onAction:           provider.clearFilters,
/// )
///
/// // Error state
/// EmptyState(
///   icon:        Icons.cloud_off_rounded,
///   title:       'Could Not Load Data',
///   message:     'Check your connection and try again.',
///   color:       AppColors.offline,
///   actionLabel: 'Retry',
///   onAction:    provider.loadDevices,
/// )
/// ```
///
/// Used by:
///   device_list_screen.dart, alerts_screen.dart,
///   notifications_screen.dart, technician_dashboard.dart
class EmptyState extends StatefulWidget {
  final IconData     icon;
  final String       title;
  final String       message;
  final Color?       color;          // icon and button accent colour
  final String?      actionLabel;
  final VoidCallback? onAction;
  final String?      secondaryLabel; // optional second button
  final VoidCallback? onSecondary;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    // Short delay so it doesn't fire during the parent's build
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.color ?? AppColors.primary;
    final iconBg      = accentColor.withOpacity(0.1);

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 40, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Icon container ────────────────────────────────────
                Container(
                  width:      84,
                  height:     84,
                  decoration: BoxDecoration(
                    color:        iconBg,
                    shape:        BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:      accentColor.withOpacity(0.12),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size:  40,
                    color: accentColor,
                  ),
                ),

                const SizedBox(height: 22),

                // ── Title ─────────────────────────────────────────────
                Text(
                  widget.title,
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // ── Message ───────────────────────────────────────────
                Text(
                  widget.message,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.6),
                  textAlign: TextAlign.center,
                ),

                // ── Primary action ────────────────────────────────────
                if (widget.actionLabel != null &&
                    widget.onAction != null) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () {
                        AppUtils.haptic();
                        widget.onAction!();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize:     const Size(double.infinity, 46),
                        elevation:       0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize:   15,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Secondary action ──────────────────────────────────
                if (widget.secondaryLabel != null &&
                    widget.onSecondary != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 200,
                    child: TextButton(
                      onPressed: () {
                        AppUtils.hapticSelect();
                        widget.onSecondary!();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize:
                            const Size(double.infinity, 42),
                      ),
                      child: Text(
                        widget.secondaryLabel!,
                        style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}