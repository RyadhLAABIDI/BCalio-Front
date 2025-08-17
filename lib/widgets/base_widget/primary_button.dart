import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class PrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final bool? isOutlined;

  const PrimaryButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.isDisabled = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isOutlined == true
              ? Colors.transparent
              : isDisabled
                  ? theme.colorScheme.onSurfaceVariant.withOpacity(0.3)
                  : theme.colorScheme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOutlined == true
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDisabled
                ? theme.colorScheme.onSurfaceVariant
                : isOutlined == true
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
          ),
        ),
      ).animate().scale(duration: 200.ms, curve: Curves.easeInOut).fadeIn(duration: 300.ms),
    );
  }
}