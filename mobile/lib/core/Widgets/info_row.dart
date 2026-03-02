import 'package:flutter/material.dart';
import '../theme.dart';

/// InfoRow displays a single label-value pair in a horizontal row.
/// Used on detail screens to show device properties like IP address,
/// MAC address, location, SNMP community string etc.
class InfoRow extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData? icon;
  final Color?    valueColor;
  final bool      isLast; // if true, hides the bottom divider

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Optional icon
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
              ],

              // Label on the left
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color:    AppColors.textSecondary,
                  ),
                ),
              ),

              // Value on the right — expands to fill remaining space
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                    color:      valueColor ?? AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),

        // Divider between rows, hidden for the last row
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}