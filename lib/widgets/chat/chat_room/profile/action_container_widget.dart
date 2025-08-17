import 'package:flutter/material.dart';

class ActionContainer extends StatelessWidget {
  const ActionContainer({
    super.key,
    this.icon, // Make icon optional
    this.imagePath, // Add imagePath parameter
    required this.color,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || imagePath != null,
  'Either icon or imagePath must be provided.');

  final IconData? icon; // Make icon optional
  final String? imagePath; // Add imagePath parameter
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.42,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display either the icon or the image
            if (icon != null)
              Icon(icon, size: 28, color: color)
            else if (imagePath != null)
              Image.asset(
                imagePath!, // Load image from assets
                width: 30, // Adjust the size as needed
                height: 30, // Adjust the size as needed
              ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}