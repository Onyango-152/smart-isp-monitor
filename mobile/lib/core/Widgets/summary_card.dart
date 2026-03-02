import 'package:flutter/material.dart';
import '../theme.dart';

/// SummaryCard displays a single KPI number with a label and icon.
/// It is used in the dashboard header row to give a quick overview
/// of the network state at a glance.
class SummaryCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final Color    backgroundColor;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Each card takes up equal space in the row
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color:        backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon at the top
            Container(
              padding:    const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:        color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),

            // The main number — large and bold
            Text(
              value,
              style: TextStyle(
                fontSize:   24,
                fontWeight: FontWeight.bold,
                color:      color,
              ),
            ),
            const SizedBox(height: 2),

            // Label below the number
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color:    AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}