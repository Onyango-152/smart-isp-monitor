import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils.dart';

/// SummaryCard displays a single KPI metric with an animated counter,
/// icon, label, and optional tap navigation.
///
/// Used by:
///   - technician_dashboard.dart  (network overview row)
///   - manager_dashboard_screen.dart
///
/// The value animates from 0 → [intValue] on first build when
/// [animate] is true (default). Pass animate: false for cards
/// that show non-numeric values.
///
/// Usage:
/// ```dart
/// SummaryCard(
///   label:    'Offline',
///   value:    '${dashboard.offlineDevices}',
///   intValue: dashboard.offlineDevices,
///   icon:     Icons.cancel_rounded,
///   color:    AppColors.offline,
///   bg:       AppColors.offlineLight,
///   onTap:    () => TechnicianShell.switchTab(context, 2),
/// )
/// ```
class SummaryCard extends StatefulWidget {
  final String       label;
  final String       value;    // displayed as-is when animate is false
  final int?         intValue; // drives the counter animation
  final IconData     icon;
  final Color        color;
  final Color        backgroundColor;
  final VoidCallback? onTap;
  final bool         animate;
  final bool         showBadge; // red dot for cards needing attention
  final bool         showIcon;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.intValue,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
    this.animate  = true,
    this.showBadge = false,
    this.showIcon = true,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<int>      _counter;
  late final Animation<double>   _fadeIn;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    );

    final target = widget.intValue ?? 0;

    _counter = IntTween(begin: 0, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    if (widget.animate && widget.intValue != null) {
      // Small delay so all cards on a row start together
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _ctrl.forward();
      });
    } else {
      _ctrl.value = 1.0; // jump to end — no animation
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool tappable = widget.onTap != null;

    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: tappable
              ? () {
                  AppUtils.haptic();
                  widget.onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow:    AppShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  if (widget.showIcon) ...[
                    // ── Icon row with optional badge ────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width:  38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: widget.backgroundColor,
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.icon,
                                color: widget.color,
                                size:  20,
                              ),
                            ),
                            if (widget.showBadge)
                              Positioned(
                                right: -3,
                                top:   -3,
                                child: Container(
                                  width:  10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color:  AppColors.offline,
                                    shape:  BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        if (tappable)
                          Icon(
                            Icons.arrow_forward_rounded,
                            size:  13,
                            color: widget.color.withOpacity(0.5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Animated counter value ──────────────────────────
                  AnimatedBuilder(
                    animation: _counter,
                    builder:   (context, _) {
                      final display = widget.animate &&
                              widget.intValue != null
                          ? '${_counter.value}'
                          : widget.value;
                      return Text(
                        display,
                        style: AppTextStyles.display.copyWith(
                          color:    widget.color,
                          fontSize: 26,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 3),

                  // ── Label ───────────────────────────────────────────
                  Text(
                    widget.label,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}