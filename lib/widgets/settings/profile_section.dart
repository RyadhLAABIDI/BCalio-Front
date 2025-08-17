import 'package:bcalio/controllers/language_controller.dart';
import 'package:bcalio/screens/settings/update_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/user_controller.dart';

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userController = Get.find<UserController>();

    return Obx(() {
      final user = userController.currentUser.value;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with Edit Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () async {
                    // Navigation améliorée avec animation moderne
                    await Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                             UpdateProfileScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOutQuart;
                          
                          final tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 600),
                      ),
                    );
                    // Refresh user info after returning from the Update Profile screen
                    userController.debugUserInfo();
                  },
                  icon: const Icon(Iconsax.edit, color: Colors.grey),
                  tooltip: 'Edit Profile',
                ),
              ],
            ),

            // Profile Picture
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              backgroundImage:
                  user?.image != null ? NetworkImage(user!.image!) : null,
              child: user?.image == null
                  ? Text(
                      _getInitials(user?.name),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // User Name
            Text(
              user?.name ?? "No name provided",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Email
            Text(
              user?.email ?? "No email provided",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            /*
            // About Section
            Text(
             user?.about ?? "No about info provided",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),*/
            const SizedBox(height: 24),

            // Phone Section
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/3d_icons/number_icon.png', // Path to the image asset
                    width: 24, // Adjust the size as needed
                    height: 24, // Adjust the size as needed
                  ),
                ),
                const SizedBox(width: 16),

                // Phone Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "phone_number".tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        textDirection: TextDirection.ltr,
                        user?.phoneNumber ?? "No phone number provided",
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Get initials (first two letters) from the user's name
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) {
      return "NA";
    }
    final words = name.split(' ');
    if (words.length == 1) {
      return words.first.substring(0, 2).toUpperCase();
    }
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  String _formatPhoneNumber(String? phoneNumber, String language) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return "No phone number provided";
    }

    // Remove any non-digit characters for consistent formatting
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Format the number based on language
    if (language == "ar") {
      // Add spaces for better readability (e.g., "+216 253 654 44")
      return cleanedNumber.replaceAllMapped(
        RegExp(r'(\d{3})(\d{3})(\d{3,})'),
        (match) => "${match[1]} ${match[2]} ${match[3]}",
      );
    }

    // Default formatting for other languages (e.g., "+216 25365444")
    return cleanedNumber.replaceAllMapped(
      RegExp(r'(\d{3})(\d{3})(\d{3,})'),
      (match) => "${match[1]} ${match[2]} ${match[3]}",
    );
  }
}