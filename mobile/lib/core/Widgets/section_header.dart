import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils.dart';

/// SectionHeader renders a titled section divider with an optional
/// subtitle, leading icon or accent bar, and a right-side action button.
///
/// Used throughout detail screens and dashboards to separate content
/// into clearly labelled sections.
///
/// Variants:
///   - Default: left blue accent bar + bold title
///   - With subtitle: smaller grey text beneath the title
///   - With icon: coloured icon replaces the accent bar
///   - With action: "See All →" button on the right
///
/// Usage:
/// ```dart
/// // Simple
/// SectionHeader(title: 'Fleet Status')
///
/// // With subtitle and action
/// SectionHeader(
///   title:       'All Devices',
///   subtitle:    '${devices.length} devices monitored',
///   actionLabel: 'See All',
///   onAction:    () => TechnicianShell.switchTab(context, 1),
/// )
///
/// // With icon
/// SectionHeader(
///   title: 'Performance Metrics',
///   icon:  Icons.speed_rounded,
/// )
/// ```
///
/// Used by:
///   technician_dashboard.dart, device_detail_screen.dart,
///   alerts_screen.dart, manager_dashboard_screen.dart
class SectionHeader extends StatelessWidget {
  final String       title;
  final String?      subtitle;
  final String?      actionLabel;
  final VoidCallback? onAction;
  final IconData?    icon;       // replaces accent bar when provided
  final Color?       iconColor;  // defaults to AppColors.primary

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Leading: accent bar OR icon ─────────────────────────────
          _buildLeading(),
          const SizedBox(width: 10),

          // ── Title + subtitle ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.heading2),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),

          // ── Action button ───────────────────────────────────────────
          if (actionLabel != null && onAction != null)
            _buildAction(),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildLeading() {
    final color = iconColor ?? AppColors.primary;

    if (icon != null) {
      // Icon variant — coloured icon in a tinted rounded square
      return Container(
        width:      32,
        height:     32,
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 17),
      );
    }

    // Default — blue accent bar
    return Container(
      width:      3,
      height:     20,
      decoration: BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAction() {
    return TextButton(
      onPressed: () {
        AppUtils.hapticSelect();
        onAction!();
      },
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(actionLabel!, style: AppTextStyles.label.copyWith(
            color:      AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize:   13,
          )),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_forward_rounded,
              size: 13, color: AppColors.primary),
        ],
      ),
    );
  }
}