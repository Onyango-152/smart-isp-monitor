import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'constants.dart';
import '../core/theme.dart';

/// AppUtils contains helper functions used across multiple screens.
/// Putting shared logic here avoids repeating the same code in every file.
class AppUtils {
  AppUtils._();

  /// Returns the correct colour for a device status string.
  /// Used by status badges and list items across the app.
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case AppConstants.statusOnline:   return AppColors.online;
      case AppConstants.statusOffline:  return AppColors.offline;
      case AppConstants.statusDegraded: return AppColors.degraded;
      default:                          return AppColors.unknown;
    }
  }

  /// Returns the background colour for a status badge.
  static Color statusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case AppConstants.statusOnline:   return AppColors.onlineLight;
      case AppConstants.statusOffline:  return AppColors.offlineLight;
      case AppConstants.statusDegraded: return AppColors.degradedLight;
      default:                          return AppColors.primarySurface;
    }
  }

  /// Returns the correct colour for an alert severity string.
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case AppConstants.severityLow:      return AppColors.severityLow;
      case AppConstants.severityMedium:   return AppColors.severityMedium;
      case AppConstants.severityHigh:     return AppColors.severityHigh;
      case AppConstants.severityCritical: return AppColors.severityCritical;
      default:                            return AppColors.unknown;
    }
  }

  /// Returns a human-readable device type label.
  static String deviceTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'router':       return 'Router';
      case 'switch':       return 'Switch';
      case 'olt':          return 'OLT';
      case 'access_point': return 'Access Point';
      case 'server':       return 'Server';
      default:             return 'Other';
    }
  }

  /// Returns the correct icon for a device type.
  static IconData deviceTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'router':       return Icons.router;
      case 'switch':       return Icons.device_hub;
      case 'olt':          return Icons.fiber_manual_record;
      case 'access_point': return Icons.wifi;
      case 'server':       return Icons.dns;
      default:             return Icons.devices_other;
    }
  }

  /// Formats a UTC ISO timestamp string into a readable local time.
  /// For example '2025-03-02T07:55:00Z' becomes '02 Mar 2025, 10:55 AM'
  static String formatDateTime(String? isoString) {
    if (isoString == null) return 'Never';
    try {
      final dt       = DateTime.parse(isoString).toLocal();
      final formatter = DateFormat('dd MMM yyyy, hh:mm a');
      return formatter.format(dt);
    } catch (_) {
      return isoString;
    }
  }

  /// Returns a relative time string like '5 minutes ago' or '2 hours ago'.
  static String timeAgo(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final dt   = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60)  return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24)  return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Formats bytes per second into a readable bandwidth string.
  /// For example 45000000 becomes '45.0 Mbps'
  static String formatBandwidth(int? bps) {
    if (bps == null) return 'N/A';
    if (bps >= 1000000000) return '${(bps / 1000000000).toStringAsFixed(1)} Gbps';
    if (bps >= 1000000)    return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
    if (bps >= 1000)       return '${(bps / 1000).toStringAsFixed(1)} Kbps';
    return '$bps bps';
  }

  /// Formats uptime seconds into a human-readable string.
  static String formatUptime(int? seconds) {
    if (seconds == null) return 'N/A';
    final days    = seconds ~/ 86400;
    final hours   = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600)  ~/ 60;
    if (days > 0)   return '${days}d ${hours}h ${minutes}m';
    if (hours > 0)  return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  /// Shows a snackbar message at the bottom of the screen.
  /// Used for success confirmations and error notifications.
  static void showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:          Text(message),
        backgroundColor:  isError ? AppColors.offline : AppColors.online,
        behavior:         SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}