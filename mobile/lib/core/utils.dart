import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import 'theme.dart'; // same folder: lib/core/theme.dart

/// AppUtils contains stateless helper functions shared across the entire app.
///
/// Rules:
///   - Every method is static — never instantiate AppUtils
///   - No state, no side-effects except showSnackbar / haptic helpers
///   - All colour logic lives here so screens never hardcode status colours
///
/// Imported by:
///   Every screen and widget that needs colour resolution, formatting,
///   or snackbar display.
class AppUtils {
  AppUtils._();

  // ── Status colours ────────────────────────────────────────────────────────

  /// Foreground / icon colour for a device status string.
  ///
  /// Usage: `color: AppUtils.statusColor(device.status)`
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case AppConstants.statusOnline:    return AppColors.online;
      case AppConstants.statusOffline:   return AppColors.offline;
      case AppConstants.statusDegraded:  return AppColors.degraded;
      case AppConstants.statusUnknown:   return AppColors.unknown;
      default:                           return AppColors.unknown;
    }
  }

  /// Light background tint for a status badge or card border fill.
  ///
  /// Usage: `color: AppUtils.statusBgColor(device.status)`
  static Color statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case AppConstants.statusOnline:    return AppColors.onlineLight;
      case AppConstants.statusOffline:   return AppColors.offlineLight;
      case AppConstants.statusDegraded:  return AppColors.degradedLight;
      default:                           return AppColors.primarySurface;
    }
  }

  /// Dark-mode background tint for status — used in dark-themed cards.
  static Color statusDarkBgColor(String status) {
    switch (status.toLowerCase()) {
      case AppConstants.statusOnline:    return AppColors.onlineDark;
      case AppConstants.statusOffline:   return AppColors.offlineDark;
      case AppConstants.statusDegraded:  return AppColors.degradedDark;
      default:                           return AppColors.primaryDarkSurface;
    }
  }

  // ── Severity colours ──────────────────────────────────────────────────────

  /// Foreground / icon colour for an alert severity string.
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case AppConstants.severityLow:      return AppColors.severityLow;
      case AppConstants.severityMedium:   return AppColors.severityMedium;
      case AppConstants.severityHigh:     return AppColors.severityHigh;
      case AppConstants.severityCritical: return AppColors.severityCritical;
      default:                            return AppColors.unknown;
    }
  }

  /// Light background tint for a severity badge.
  ///
  /// Usage: `color: AppUtils.severityBgColor(alert.severity)`
  static Color severityBgColor(String severity) {
    switch (severity.toLowerCase()) {
      case AppConstants.severityLow:      return AppColors.primarySurface;
      case AppConstants.severityMedium:   return AppColors.degradedLight;
      case AppConstants.severityHigh:     return AppColors.offlineLight;
      case AppConstants.severityCritical: return AppColors.maintenanceLight;
      default:                            return AppColors.primarySurface;
    }
  }

  /// Human-readable label for a severity value.
  static String severityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case AppConstants.severityLow:      return 'Low';
      case AppConstants.severityMedium:   return 'Medium';
      case AppConstants.severityHigh:     return 'High';
      case AppConstants.severityCritical: return 'Critical';
      default:                            return 'Unknown';
    }
  }

  // ── Latency colours ───────────────────────────────────────────────────────

  /// Colour for a latency value in milliseconds.
  ///
  /// < 50 ms  → green (good)
  /// < 200 ms → amber (acceptable)
  /// ≥ 200 ms → red   (poor)
  ///
  /// Used by: DiagnosticScreen, DeviceDetailScreen, device cards
  static Color latencyColor(double ms) {
    if (ms < 50)  return AppColors.online;
    if (ms < 200) return AppColors.degraded;
    return AppColors.offline;
  }

  /// Light background tint for a latency chip.
  static Color latencyBgColor(double ms) {
    if (ms < 50)  return AppColors.onlineLight;
    if (ms < 200) return AppColors.degradedLight;
    return AppColors.offlineLight;
  }

  /// Human-readable latency quality label.
  static String latencyLabel(double ms) {
    if (ms < 50)  return 'Good';
    if (ms < 200) return 'Fair';
    return 'Poor';
  }

  // ── Device type helpers ───────────────────────────────────────────────────

  /// Human-readable label for a device type string.
  static String deviceTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case AppConstants.deviceRouter:      return 'Router';
      case AppConstants.deviceSwitch:      return 'Switch';
      case AppConstants.deviceOlt:         return 'OLT';
      case AppConstants.deviceAccessPoint: return 'Access Point';
      case 'server':                       return 'Server';
      default:                             return 'Device';
    }
  }

  /// Rounded icon for a device type — matches the icon style used in cards.
  static IconData deviceTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case AppConstants.deviceRouter:      return Icons.router_rounded;
      case AppConstants.deviceSwitch:      return Icons.device_hub_rounded;
      case AppConstants.deviceOlt:         return Icons.lan_rounded;
      case AppConstants.deviceAccessPoint: return Icons.wifi_rounded;
      case 'server':                       return Icons.dns_rounded;
      default:                             return Icons.memory_rounded;
    }
  }

  // ── Date / time formatting ────────────────────────────────────────────────

  /// Full datetime: "02 Mar 2025, 10:55 AM"
  static String formatDateTime(String? isoString) {
    if (isoString == null) return 'Never';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  /// Short date for chart axis labels: "Mar 02"
  static String formatShortDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM dd').format(dt);
    } catch (_) {
      return '';
    }
  }

  /// Time only: "10:55 AM"
  static String formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  /// Relative time: "5s ago", "3m ago", "2h ago", "4d ago"
  ///
  /// Used by: device tiles, alert cards, notification items
  static String timeAgo(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final dt   = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24)  return '${diff.inHours}h ago';
      if (diff.inDays    < 30)  return '${diff.inDays}d ago';
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return 'Unknown';
    }
  }

  // ── Numeric formatting ────────────────────────────────────────────────────

  /// Formats bytes-per-second into a readable bandwidth string.
  ///
  /// 45_000_000 → "45.0 Mbps"
  static String formatBandwidth(int? bps) {
    if (bps == null) return 'N/A';
    if (bps >= 1000000000)
      return '${(bps / 1000000000).toStringAsFixed(1)} Gbps';
    if (bps >= 1000000)
      return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    if (bps >= 1000)
      return '${(bps / 1000).toStringAsFixed(1)} Kbps';
    return '$bps bps';
  }

  /// Formats uptime seconds into a human-readable duration string.
  ///
  /// 90061 → "1d 1h 1m"
  static String formatUptime(int? seconds) {
    if (seconds == null) return 'N/A';
    final days    = seconds ~/ 86400;
    final hours   = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600)  ~/ 60;
    if (days > 0)  return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Formats a percentage to one decimal place with a % suffix.
  ///
  /// 99.123 → "99.1%"
  static String formatPercent(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Formats a latency value with ms suffix.
  ///
  /// 45.6 → "46 ms"
  static String formatLatency(double? ms) {
    if (ms == null) return 'N/A';
    return '${ms.toStringAsFixed(0)} ms';
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  /// Shows a floating snackbar using the app's SnackBarTheme.
  ///
  /// Pass `isError: true` for failure messages — shows a red leading icon.
  /// Pass `isError: false` (default) for success — shows a green check icon.
  ///
  /// The theme's backgroundColor, shape, and behavior are applied
  /// automatically from AppTheme — do NOT override them here.
  ///
  /// Used by: every screen that needs user feedback after an action.
  static void showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: isError
                    ? const Color(0xFFF87171)
                    : Colors.greenAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          // Errors stay longer so users have time to read them
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
  }

  /// Light haptic tap — call on important button presses.
  ///
  /// Usage: `AppUtils.haptic()`
  static void haptic() => HapticFeedback.lightImpact();

  /// Selection click — call on tab switches and chip/filter toggles.
  static void hapticSelect() => HapticFeedback.selectionClick();
}