import 'package:flutter/material.dart';
// import '../theme.dart';
import '../utils.dart';

/// StatusBadge displays a device's current status with appropriate colors and styling.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({
    required this.status,
    this.small = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.statusColor(status);
    final label = status[0].toUpperCase() + status.substring(1).toLowerCase();
    final fontSize = small ? 10.0 : 12.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}