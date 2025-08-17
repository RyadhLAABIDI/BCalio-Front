import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StyledInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final String? imagePath;
  final TextInputType inputType;
  final Widget? trailing;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final bool? enabled;

  const StyledInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.icon,
    this.imagePath,
    this.inputType = TextInputType.text,
    this.trailing,
    this.obscureText = false,
    this.onChanged,
    this.enabled,
  }) : assert(icon != null || imagePath != null, 'Either icon or imagePath must be provided.');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            boxShadow: enabled == false
                ? []
                : [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: inputType,
            obscureText: obscureText,
            onChanged: onChanged,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              prefixIcon: imagePath != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        imagePath!,
                        width: 24,
                        height: 24,
                      ),
                    )
                  : icon != null
                      ? Icon(
                          icon,
                          color: theme.colorScheme.primary,
                        )
                      : null,
              suffixIcon: trailing,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            ),
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
  }
}