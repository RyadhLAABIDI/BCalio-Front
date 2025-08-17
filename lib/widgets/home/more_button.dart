import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../screens/settings/settings_screen.dart';

class MoreButton extends StatelessWidget {
  const MoreButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<int>(
      splashRadius: 24,
      icon: const Icon(Iconsax.more_circle, color: Colors.white),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (value) {
        switch (value) {
          case 0:
            Get.to(() => const SettingsScreen()); // Navigate to Settings
            break;
          case 1:
            debugPrint("New Group----------------------------------------");
            Get.toNamed('/createGroup'); // Navigate to New Group
            break;
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 0,
            child: Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                // Image.asset(
                //   "assets/3d_icons/settings_icon.png", // Path to the image asset for Settings
                //   width: 24, // Adjust the size as needed
                //   height: 24, // Adjust the size as needed
                // ),
                const SizedBox(width: 12),
                Text(
                  "Settings".tr, // Translatable label
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 1,
            child: Row(
              children: [
                Icon(Icons.person, color: theme.colorScheme.primary),
                // Image.asset(
                //   "assets/3d_icons/user_icon.png", // Path to the image asset for New Group
                //   width: 24, // Adjust the size as needed
                //   height: 24, // Adjust the size as needed
                // ),
                const SizedBox(width: 12),
                Text(
                  "New Group".tr, // Translatable label
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
