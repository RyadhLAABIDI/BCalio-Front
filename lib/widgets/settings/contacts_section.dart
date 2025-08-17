import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../controllers/contact_controller.dart';

class ContactsSectionSection extends StatelessWidget {
  const ContactsSectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final contactController = Get.find<ContactController>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title with Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.personalcard, // Use Iconsax notification icon
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "allow_contacts".tr, // Use translation key for notifications
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(), // Push the button to the right
              // Show loading indicator until permission is checked
              Obx(() {
                if (contactController.isLoading.value) {
                  return CircularProgressIndicator(); // Show loading indicator
                }

                return ElevatedButton(
                  onPressed: () async {
                    if (!contactController.isPermissionGranted.value) {
                      await contactController.requestContactsPermission();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: contactController.isPermissionGranted.value
                        ? theme.iconTheme.color
                        : theme.colorScheme.error,
                    shape: CircleBorder(),
                    padding: const EdgeInsets.all(8),
                    minimumSize: Size(30, 30),
                  ),
                  child: Icon(
                    contactController.isPermissionGranted.value
                        ? Icons.check
                        : Iconsax.close_circle,
                    color: theme.colorScheme.onPrimary,
                    size: 18,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
