import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class ContactListTile extends StatelessWidget {
  final String name;
  final String phoneNumber;
  final String? avatarUrl;
  final VoidCallback onTap;
  final Widget? trailing; // Optional trailing widget

  const ContactListTile({
    super.key,
    required this.name,
    required this.phoneNumber,
    this.avatarUrl,
    required this.onTap,
    this.trailing, // Add trailing parameter
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Expanded(
              flex: 1,
              child: CircleAvatar(
                radius: 30,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(avatarUrl!)
                    : null,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: avatarUrl == null || avatarUrl == ""
                    ? Text(
                        name[0].toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            // Contact Info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.call,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          phoneNumber,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Optional trailing widget
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
