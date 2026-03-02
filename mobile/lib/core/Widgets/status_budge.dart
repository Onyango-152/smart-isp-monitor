import 'package:flutter/material.dart';
import '../utils.dart';

/// StatusBadge is a small coloured pill that displays a device or
/// alert status. It is used on the device list, device detail,
/// dashboard cards, and alert cards throughout the app.
class StatusBadge extends StatelessWidget {
  final String status;
  final bool   small;

  const StatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final color      = AppUtils.statusColor(status);
    final background = AppUtils.statusBackgroundColor(status);
    final label      = status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8  : 12,
        vertical:   small ? 3  : 5,
      ),
      decoration: BoxDecoration(
        color:        background,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small coloured dot before the label
          Container(
            width:  small ? 6 : 8,
            height: small ? 6 : 8,
            decoration: BoxDecoration(
              color:  color,
              shape:  BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   small ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}