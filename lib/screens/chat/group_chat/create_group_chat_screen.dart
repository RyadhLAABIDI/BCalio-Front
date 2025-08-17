import 'dart:io';
import 'package:bcalio/controllers/contact_controller.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/models/contact_model.dart';
import 'package:bcalio/models/true_user_model.dart';
import 'package:bcalio/routes.dart';
import 'package:bcalio/services/contact_api_service.dart';
import 'package:bcalio/services/sms_verification_service.dart';
import 'package:bcalio/widgets/base_widget/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/group_chat_controller.dart';
import '../../../themes/theme.dart';
import '../../../widgets/base_widget/custom_loading_indicator.dart';
import '../../../widgets/base_widget/custom_search_bar.dart';
import '../../../widgets/base_widget/no_search_found.dart';
import '../../../widgets/base_widget/otp_loading_indicator.dart';
import '../../../widgets/contacts/group/ContactTileGroup.dart';

class CreateGroupChatScreen extends StatefulWidget {
  CreateGroupChatScreen({super.key});

  @override
  State<CreateGroupChatScreen> createState() => _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends State<CreateGroupChatScreen> {
  final GroupChatController controller = Get.put(GroupChatController());
  final SmsVerificationService smsService = SmsVerificationService();
  final RxBool isLoading = false.obs;
  final UserController userController = Get.find<UserController>();
  final TextEditingController _groupNameController = TextEditingController();
  final RxString _selectedImage = ''.obs;
  final ImagePicker _picker = ImagePicker();

  final ContactController contactController = Get.put(
    ContactController(contactApiService: ContactApiService()),
  );

  @override
  initState() {
    super.initState();
    debugPrint('GroupChat screen onInit----------------------------');
    contactController.loadContactPermissionPreference();
    contactController.checkContactsPermission();
    contactController.loadCachedContacts();
  }

  String normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String removeSubstring(String input) {
    int plusIndex = input.indexOf("+");
    if (plusIndex == -1) return input;
    int spaceIndex = input.indexOf(" ", plusIndex);
    if (spaceIndex == -1) return input.substring(0, plusIndex);
    return input.substring(0, plusIndex) + input.substring(spaceIndex);
  }

  Future<void> _handleAddContact(RxList<Contact> contacts) async {
    try {
      isLoading.value = true;
      final message =
          "Try B-callio Now! Download it from Google Play: https://play.google.com/store/apps/details?id=com.elite.bcalio&pcampaignid=web_share";
      for (var contact in contacts) {
        debugPrint('phone number contact ============${removeSubstring(contact.phoneNumber!)}');
        if (contact.isPhoneContact) {
          await smsService.sendMessage(
            removeSubstring(contact.phoneNumber!),
            message,
          ).then((success) {
            showSuccessSnackbar("success_invitation_sent_to_contact".tr);
          }).onError((error, stackTrace) {
            showErrorSnackbar("error_failed_to_send_invitation_to_contact".tr);
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling add contact: $e');
      showErrorSnackbar("Failed to handle add contact: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handleAddSingleContact(Contact contact) async {
    try {
      final message =
          "Try B-callio Now! Download it from Google Play: https://play.google.com/store/apps/details?id=com.elite.bcalio&pcampaignid=web_share";
      debugPrint('Sending SMS to: ${contact.phoneNumber}');
      final success = await smsService.sendMessage(
        removeSubstring(contact.phoneNumber!),
        message,
      );

      if (success) {
        showSuccessSnackbar("Succès, invitation envoyée à ${contact.name}");
      } else {
        showErrorSnackbar("Erreur, échec de l'envoi de l'invitation à ${contact.name}");
      }
    } catch (e) {
      debugPrint('Error sending single invitation: $e');
      showErrorSnackbar("Échec de l'envoi de l'invitation: $e");
    }
  }

  void _resetState() {
    // Réinitialiser les contacts sélectionnés
    controller.selectedContacts.clear();
    // Réinitialiser le nom du groupe
    _groupNameController.clear();
    controller.groupNameController.clear();
    // Réinitialiser l'image du groupe
    _selectedImage.value = '';
    controller.groupLogoController.clear();
  }

  void _showGroupCreationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar selector
              GestureDetector(
                onTap: () async {
                  try {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final File file = File(image.path);
                      final imageUrl = await controller.uploadLogoToCloudinary(file);
                      if (imageUrl != null) {
                        _selectedImage.value = imageUrl;
                        controller.groupLogoController.text = imageUrl;
                      }
                    }
                  } catch (e) {
                    showErrorSnackbar("Échec de la sélection de l'image: $e".tr);
                  }
                },
                child: Obx(() => CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: _selectedImage.value.isNotEmpty
                          ? NetworkImage(_selectedImage.value)
                          : null,
                      child: _selectedImage.value.isEmpty
                          ? Icon(
                              Iconsax.camera,
                              size: 32,
                              color: theme.colorScheme.onPrimaryContainer,
                            )
                          : null,
                    )),
              ),
              const SizedBox(height: 16),
              // Group name input
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: "Nom du groupe".tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Annuler".tr,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_groupNameController.text.isNotEmpty) {
                          controller.groupNameController.text = _groupNameController.text;
                          final hasPhoneNumber = controller.selectedContacts
                              .any((contact) => contact.isPhoneContact == true);
                          if (hasPhoneNumber) {
                            await _handleAddContact(controller.selectedContacts);
                          }
                          Navigator.pop(context); // Ferme le bottom sheet
                          await controller.createGroupChat(
                            context,
                            _groupNameController.text,
                            logoUrl: _selectedImage.value.isNotEmpty ? _selectedImage.value : null,
                          );
                          _resetState(); // Réinitialiser l'état après la création
                        } else {
                          showErrorSnackbar("Veuillez entrer un nom de groupe".tr);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Créer".tr,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Obx(() {
      return Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              flexibleSpace: Container(
                color: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
              ),
              title: Text(
                "Create Group Chat".tr,
                style: theme.appBarTheme.titleTextStyle?.copyWith(
                  color: isDarkMode ? kHighlightColor : kDarkBgColor,
                ),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Iconsax.arrow_left),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                Obx(() => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Text(
                        "${controller.selectedContacts.length}",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDarkMode ? kHighlightColor : kDarkBgColor,
                        ),
                      ),
                    )),
              ],
            ),
            floatingActionButton: Obx(() {
              final hasSelectedContacts = controller.selectedContacts.length >= 2;
              return AnimatedOpacity(
                opacity: hasSelectedContacts ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: hasSelectedContacts
                    ? FloatingActionButton.extended(
                        onPressed: () => _showGroupCreationBottomSheet(context),
                        backgroundColor: theme.colorScheme.primary,
                        label: Text(
                          "Create Group".tr,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        icon: Icon(
                          Iconsax.user_add,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Select contacts to create a group chat.".tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  CustomSearchBar(
                    hintText: "Search Contacts".tr,
                    onChanged: (query) => controller.searchContacts(query.trim()),
                  ),
                  const SizedBox(height: 16),
                  // Selected Contacts Section
                  Obx(() {
                    if (controller.selectedContacts.isNotEmpty) {
                      return SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: controller.selectedContacts.length,
                          itemBuilder: (context, index) {
                            final contact = controller.selectedContacts[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage:
                                        contact.image != null ? NetworkImage(contact.image!) : null,
                                    child: contact.image == null
                                        ? Text(contact.name[0].toUpperCase())
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () => controller.toggleSelection(contact),
                                      child: CircleAvatar(
                                        radius: 12,
                                        backgroundColor: theme.colorScheme.error,
                                        child: const Icon(
                                          Iconsax.close_circle,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 16),
                  // Contacts List
                  Expanded(
                    child: Obx(() {
                      if (controller.isFetchingContacts.value) {
                        return  Center(child: CustomLoadingIndicator());
                      }
                      if (controller.filteredContacts.isEmpty) {
                        return NoSearchFound(
                          message: "No contacts match your search.".tr,
                        );
                      }

                      final appContacts = controller.filteredContacts
                          .where((contact) => !contact.isPhoneContact)
                          .toList();
                      final phoneContacts = controller.filteredContacts
                          .where((contact) => contact.isPhoneContact)
                          .toList();

                      return ListView(
                        children: [
                          if (appContacts.isNotEmpty) ...[
                            _buildSectionHeader("Contacts enregistrés".tr),
                            ...appContacts.map((contact) => _buildContactTile(contact)).toList(),
                          ],
                          if (appContacts.isNotEmpty && phoneContacts.isNotEmpty)
                            _buildSectionDivider("Contacts non enregistrés".tr),
                          if (phoneContacts.isNotEmpty) ...[
                            ...phoneContacts.map((contact) => _buildContactTile(contact)).toList(),
                          ],
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          if (controller.isLoading.value || isLoading.value)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: OtpLoadingIndicator(),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSectionDivider(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(Contact contact) {
    return Obx(() {
      final isSelected = controller.selectedContacts.contains(contact);
      return ContactTileGroup(
        name: contact.name,
        phoneNumber: contact.phoneNumber ?? 'N/A',
        avatarUrl: contact.image,
        isSelected: isSelected,
        onTap: () => controller.toggleSelection(contact),
        isPhoneContact: contact.isPhoneContact,
        contact: contact,
        onAddContact: () => _handleAddSingleContact(contact),
      );
    });
  }
}