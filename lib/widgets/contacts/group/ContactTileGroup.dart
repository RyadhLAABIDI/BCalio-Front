import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/models/contact_model.dart';
import 'package:bcalio/models/true_user_model.dart';
import 'package:bcalio/screens/contacts/modern_loading_indicator.dart';
import 'package:bcalio/services/contact_api_service.dart';
import 'package:bcalio/services/sms_verification_service.dart';
import 'package:bcalio/widgets/base_widget/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

class ContactTileGroup extends StatelessWidget {
  final String name;
  final String phoneNumber;
  final String? avatarUrl;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isPhoneContact;
  final Contact contact;
  final VoidCallback? onAddContact;

  ContactTileGroup({
    super.key,
    required this.name,
    required this.phoneNumber,
    this.avatarUrl,
    required this.isSelected,
    required this.onTap,
    required this.isPhoneContact,
    required this.contact,
    this.onAddContact,
  });

  final SmsVerificationService smsService = SmsVerificationService();
  final RxBool isLoading = false.obs;
  final UserController userController = Get.find<UserController>();
  
  String normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }

  final RxBool isAddingContact = false.obs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: isPhoneContact ? null : onTap,
      child: Opacity(
        opacity: isPhoneContact ? 0.6 : 1.0,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : Border.all(color: Colors.transparent),
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
              CircleAvatar(
                radius: 30,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: avatarUrl == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              Expanded(
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
                    Text(
                      phoneNumber,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              if (isPhoneContact)
                Obx(() => isAddingContact.value
                    ? ModernLoadingIndicator(
                        size: 24,
                        color: theme.colorScheme.primary,
                      )
                    : GestureDetector(
                        onTap: () async {
                          if (onAddContact != null) {
                            isAddingContact.value = true;
                            onAddContact!();
                            isAddingContact.value = false;
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/3d_icons/user_icon.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'add'.tr,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}