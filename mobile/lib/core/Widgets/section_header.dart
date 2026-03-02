import 'package:flutter/material.dart';
import '../theme.dart';

/// SectionHeader renders a bold section title with an optional
/// action button on the right side. Used throughout the detail
/// screens to separate content into clearly labelled sections.
class SectionHeader extends StatelessWidget {
  final String    title;
  final String?   actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left border accent + title
          Row(
            children: [
              Container(
                width:        3,
                height:       18,
                margin:       const EdgeInsets.only(right: 8),
                decoration:   BoxDecoration(
                  color:        AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize:   16,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textPrimary,
                ),
              ),
            ],
          ),

          // Optional action button on the right
          if (actionLabel != null && onAction != null)
            TextButton(

              onPressed: onAction,
              style:     TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}