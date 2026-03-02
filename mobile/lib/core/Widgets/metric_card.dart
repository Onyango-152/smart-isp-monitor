import 'package:flutter/material.dart';
import '../theme.dart';

/// MetricCard displays a single metric value with a label and unit.
/// Used on device detail screens to show latency, CPU, memory etc.
class MetricCard extends StatelessWidget {
  final String   label;
  final String   value;
  final String?  unit;
  final IconData icon;
  final Color?   valueColor;
  final bool     isAlert; // highlights the card in red if value is alarming

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.valueColor,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor  = isAlert
        ? AppColors.offlineLight
        : AppColors.surface;
    final Color iconColor  = isAlert
        ? AppColors.offline
        : AppColors.primaryLight;
    final Color textColor  = valueColor ??
        (isAlert ? AppColors.offline : AppColors.textPrimary);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert
              ? AppColors.offline.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and label row
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color:    AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Alert indicator dot
              if (isAlert)
                Container(
                  width:  8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.offline,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Value and unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                  color:      textColor,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit!,
                    style: const TextStyle(
                      fontSize: 12,
                      color:    AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}