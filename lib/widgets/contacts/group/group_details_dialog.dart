import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/group_chat_controller.dart';

Future<void> showGroupDetailsDialog({
  required BuildContext context,
  required GroupChatController controller,
}) async {
  final theme = Theme.of(context);
  final ImagePicker picker = ImagePicker();
  File? selectedImage;

  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(Iconsax.messages5, color: theme.appBarTheme.backgroundColor),
            const SizedBox(width: 8),
            Text(
              "group_details".tr,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Group Name Input
                  TextField(
                    controller: controller.groupNameController,
                    decoration: InputDecoration(
                      labelText: "group_name".tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Group Logo Input
                  GestureDetector(
                    onTap: () async {
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() {
                          selectedImage = File(image.path);
                        });
                      }
                    },
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: selectedImage != null
                                  ? FileImage(selectedImage!)
                                  : null,
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              child: selectedImage == null
                                  ? Icon(
                                      Iconsax.camera,
                                      size: 40,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                            if (selectedImage != null)
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.error,
                                child: IconButton(
                                  icon: const Icon(
                                    Iconsax.close_circle,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedImage = null;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "tap_to_upload_logo".tr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          // Cancel Button
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Iconsax.close_square, color: theme.colorScheme.error),
            label: Text(
              "cancel".tr,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),

          // Create Button
ElevatedButton.icon(
  onPressed: () async {
    Navigator.of(context).pop(); // Close dialog first
    controller.isLoading.value = true; // Show full-screen loader
    try {
      // Upload logo if selected
      if (selectedImage != null) {
        final logoUrl = await controller.uploadLogoToCloudinary(selectedImage!);
        controller.groupLogoController.text = logoUrl ?? '';
      }
      // Pass the required parameters to createGroupChat
      await controller.createGroupChat(
        context,
        controller.groupNameController.text,
        logoUrl: controller.groupLogoController.text.isNotEmpty
            ? controller.groupLogoController.text
            : null,
      );
    } catch (e) {
      debugPrint('Error in createGroupChat: $e');
      Get.snackbar("Error", "Failed to create group: $e");
    } finally {
      controller.isLoading.value = false; // Hide loader
    }
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: theme.appBarTheme.backgroundColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  icon: const Icon(Iconsax.tick_circle, color: Colors.white),
  label: Text(
    "create".tr,
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
),
        ],
      );
    },
  );
}
