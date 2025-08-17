import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
//import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
//import '../../../controllers/call_service_controller.dart';
import '../../../controllers/user_controller.dart';
import '../../../themes/theme.dart';
import '../../../widgets/base_widget/custom_snack_bar.dart';
import '../../../widgets/chat/chat_room/profile/action_container_widget.dart';
import '../../../widgets/chat/chat_room/profile/info_tile_widget.dart';

class RemoteProfileScreen extends StatelessWidget {
  const RemoteProfileScreen({
    super.key,
    required this.username,
    required this.profileImageUrl,
    this.status,
    required this.phoneNumber,
    required this.email,
    required this.conversationId,
    this.createdAt,
  });

  final String username;
  final String profileImageUrl;
  final String? status;
  final String phoneNumber;
  final String email;
  final String conversationId;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    //final callController = Get.put(CallServiceController());
    final userController = Get.find<UserController>();

    // Fetch logged-in user's details
    final userID = userController.currentUser.value?.id; // Logged-in user ID
    final userName =
        userController.currentUser.value?.name; // Logged-in user name

    // Format creation date
    final formattedDate = createdAt != null
        ? "${createdAt!.year}-${createdAt!.month.toString().padLeft(2, '0')}-${createdAt!.day.toString().padLeft(2, '0')}"
        : "Unknown";

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          color: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
        ),
        title: Text(
          "Profile".tr, // Translated
          style: theme.textTheme.titleLarge?.copyWith(
            color: isDarkMode ? Colors.white : kDarkBgColor,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left,
            color: isDarkMode ? Colors.white : kDarkBgColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Profile Picture
            CircleAvatar(
              radius: 70,
              backgroundColor:
                  theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl.isEmpty
                  ? Text(
                      username.substring(0, 2).toUpperCase(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Username and Status
            Text(
              username,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ActionContainer(
                  imagePath: "assets/3d_icons/message_icon.png",
                  color: Colors.orange,
                  label: "Message".tr,
                  onTap: () {
                   Navigator.of(context).pop();
                  },
                ),
                ActionContainer(
                  imagePath: "assets/3d_icons/user_icon.png",
                  color: Colors.purple,
                  label: "Add Contact".tr, // Translated
                  onTap: () {
                    // Add contact functionality
                    Get.toNamed('/addContactScreen');
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Additional User Information
            InfoTile(
              imagePath: "assets/3d_icons/number_icon.png",
              title: "Phone Number".tr, // Translated
              value: phoneNumber,
            ),
            const SizedBox(height: 16),
            InfoTile(
              imagePath: "assets/3d_icons/about_icon.png",
              title: "About".tr, // Translated
              value: "Joined on $formattedDate".tr, // Translated
            ),
          ],
        ),
      ),
    );
  }
}