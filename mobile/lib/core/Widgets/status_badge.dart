import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils.dart';

/// StatusBadge displays a device status pill with a coloured dot and label.
///
/// Three sizes:
///   - BadgeSize.small  — used in list tiles, compact spaces (10px font)
///   - BadgeSize.medium — default, used in cards and headers (12px font)
///   - BadgeSize.large  — used in device detail app bar area (13px font)
///
/// Usage:
/// ```dart
/// StatusBadge(status: device.status)
/// StatusBadge(status: device.status, size: BadgeSize.large)
/// StatusBadge(status: device.status, size: BadgeSize.small, showDot: false)
/// ```
///
/// For alert severity badges use [SeverityBadge] below.
///
/// Used by:
///   device_list_tile.dart, device_detail_screen.dart,
///   alerts_screen.dart, device_management_screen.dart
enum BadgeSize { small, medium, large }

class StatusBadge extends StatelessWidget {
  final String    status;
  final BadgeSize size;
  final bool      showDot;

  const StatusBadge({
    super.key,
    required this.status,
    this.size    = BadgeSize.medium,
    this.showDot = true,
  });

  // ── Sizing helpers ────────────────────────────────────────────────────────

  double get _fontSize {
    switch (size) {
      case BadgeSize.small:  return 10;
      case BadgeSize.medium: return 12;
      case BadgeSize.large:  return 13;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case BadgeSize.small:  return const EdgeInsets.symmetric(horizontal: 6,  vertical: 2);
      case BadgeSize.medium: return const EdgeInsets.symmetric(horizontal: 9,  vertical: 4);
      case BadgeSize.large:  return const EdgeInsets.symmetric(horizontal: 12, vertical: 5);
    }
  }

  double get _dotSize {
    switch (size) {
      case BadgeSize.small:  return 5;
      case BadgeSize.medium: return 6;
      case BadgeSize.large:  return 7;
    }
  }

  // ── Label ─────────────────────────────────────────────────────────────────

  String get _label {
    switch (status.toLowerCase()) {
      case AppConstants.statusOnline:    return 'Online';
      case AppConstants.statusOffline:   return 'Offline';
      case AppConstants.statusDegraded:  return 'Degraded';
      case AppConstants.statusUnknown:   return 'Unknown';
      default:
        // Capitalise first letter as fallback
        return status.isEmpty
            ? 'Unknown'
            : status[0].toUpperCase() + status.substring(1).toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.statusColor(status);
    final bg    = AppUtils.statusBgColor(status);

    return Container(
      padding:    _padding,
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(
          color: color.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width:      _dotSize,
              height:     _dotSize,
              decoration: BoxDecoration(
                color:  color,
                shape:  BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            _label,
            style: TextStyle(
              fontSize:      _fontSize,
              fontWeight:    FontWeight.w600,
              color:         color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeverityBadge
// ─────────────────────────────────────────────────────────────────────────────

/// SeverityBadge displays an alert severity pill.
///
/// Mirrors the StatusBadge API but resolves colours from severity strings
/// (low / medium / high / critical) using AppUtils.severityColor/BgColor.
///
/// Usage:
/// ```dart
/// SeverityBadge(severity: alert.severity)
/// SeverityBadge(severity: alert.severity, size: BadgeSize.small)
/// ```
///
/// Used by:
///   alerts_screen.dart, alert_detail_screen.dart,
///   manager_dashboard_screen.dart, notifications_screen.dart
class SeverityBadge extends StatelessWidget {
  final String    severity;
  final BadgeSize size;
  final bool      showDot;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.size    = BadgeSize.medium,
    this.showDot = true,
  });

  double get _fontSize {
    switch (size) {
      case BadgeSize.small:  return 10;
      case BadgeSize.medium: return 12;
      case BadgeSize.large:  return 13;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case BadgeSize.small:  return const EdgeInsets.symmetric(horizontal: 6,  vertical: 2);
      case BadgeSize.medium: return const EdgeInsets.symmetric(horizontal: 9,  vertical: 4);
      case BadgeSize.large:  return const EdgeInsets.symmetric(horizontal: 12, vertical: 5);
    }
  }

  double get _dotSize {
    switch (size) {
      case BadgeSize.small:  return 5;
      case BadgeSize.medium: return 6;
      case BadgeSize.large:  return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.severityColor(severity);
    final bg    = AppUtils.severityBgColor(severity);
    final label = AppUtils.severityLabel(severity);

    return Container(
      padding:    _padding,
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(
          color: color.withOpacity(0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width:      _dotSize,
              height:     _dotSize,
              decoration: BoxDecoration(
                color:  color,
                shape:  BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize:      _fontSize,
              fontWeight:    FontWeight.w600,
              color:         color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}