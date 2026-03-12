import 'package:flutter/material.dart';
import '../utils.dart';

enum BadgeSize { small, medium, large }

/// StatusBadge — coloured pill showing device status (online/offline/degraded).
class StatusBadge extends StatelessWidget {
  final String   status;
  final BadgeSize size;
  final bool     showDot;

  const StatusBadge({
    super.key,
    required this.status,
    this.size    = BadgeSize.medium,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final color   = AppUtils.statusColor(status);
    final bgColor = AppUtils.statusBgColor(status);
    final label   = _statusLabel(status);
    final fs      = _fontSize(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == BadgeSize.small ? 7 : 9,
        vertical:   size == BadgeSize.small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width:      fs * 0.7,
              height:     fs * 0.7,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: size == BadgeSize.small ? 4 : 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize:   fs,
              fontWeight: FontWeight.w700,
              color:      color,
            ),
          ),
        ],
      ),
    );
  }

  double _fontSize(BadgeSize s) {
    switch (s) {
      case BadgeSize.small:  return 10;
      case BadgeSize.medium: return 12;
      case BadgeSize.large:  return 13;
    }
  }

  // Plain string literals — AppConstants.statusX are equivalent values
  // but Dart switch/case requires compile-time constants; raw strings
  // are always safe.
  String _statusLabel(String status) {
    switch (status) {
      case 'online':   return 'Online';
      case 'offline':  return 'Offline';
      case 'degraded': return 'Degraded';
      case 'unknown':  return 'Unknown';
      default:         return status;
    }
  }
}

/// SeverityBadge — coloured pill showing alert severity.
class SeverityBadge extends StatelessWidget {
  final String   severity;
  final BadgeSize size;

  const SeverityBadge({
    super.key,
    required this.severity,
    this.size = BadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.severityColor(severity);
    final bg    = AppUtils.severityBgColor(severity);
    final fs    = _fontSize(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size == BadgeSize.small ? 7 : 9,
        vertical:   size == BadgeSize.small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        _severityLabel(severity),
        style: TextStyle(
          fontSize:   fs,
          fontWeight: FontWeight.w700,
          color:      color,
        ),
      ),
    );
  }

  double _fontSize(BadgeSize s) {
    switch (s) {
      case BadgeSize.small:  return 10;
      case BadgeSize.medium: return 12;
      case BadgeSize.large:  return 13;
    }
  }

  String _severityLabel(String s) {
    switch (s) {
      case 'critical': return 'Critical';
      case 'high':     return 'High';
      case 'medium':   return 'Medium';
      case 'low':      return 'Low';
      case 'info':     return 'Info';
      default:         return s;
    }
  }
}
