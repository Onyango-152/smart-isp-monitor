import 'package:flutter/material.dart';
import '../theme.dart';

/// EmptyState is shown when a list has no items to display.
/// Every list screen in the app uses this widget so the user
/// always gets a helpful message instead of a blank screen.
class EmptyState extends StatelessWidget {
  final String   title;
  final String   message;
  final IconData icon;
  final String?  actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large icon
            Container(
              width:      80,
              height:     80,
              decoration: BoxDecoration(
                color:        AppColors.primarySurface,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(icon, size: 40, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 20),

            Text(
              title,
              style: const TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.bold,
                color:      AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color:    AppColors.textSecondary,
                height:   1.5,
              ),
              textAlign: TextAlign.center,
            ),

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 46),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}