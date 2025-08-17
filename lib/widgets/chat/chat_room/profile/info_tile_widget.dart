import 'package:flutter/material.dart';

class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    this.icon, // Make icon optional
    this.imagePath, // Add imagePath parameter
    required this.title,
    required this.value,
  }) : assert(icon != null || imagePath != null,
            'Either icon or imagePath must be provided.');

  final IconData? icon; // Make icon optional
  final String? imagePath; // Add imagePath parameter
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Display either the icon or the image
          if (icon != null)
            Icon(icon, size: 28, color: theme.colorScheme.primary)
          else if (imagePath != null)
            Image.asset(
              imagePath!, // Load image from assets
              width: 30, // Adjust the size as needed
              height: 30, // Adjust the size as needed
            ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
