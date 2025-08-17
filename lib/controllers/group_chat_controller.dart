import 'dart:io';

import 'package:bcalio/routes.dart';
import 'package:bcalio/widgets/base_widget/show_custom_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/contact_model.dart';
import '../controllers/contact_controller.dart';
import '../controllers/conversation_controller.dart';
import '../controllers/user_controller.dart';
import '../screens/chat/ChatRoom/chat_room_screen.dart';

class GroupChatController extends GetxController {
  final ConversationController conversationController =
      Get.find<ConversationController>();
  final ContactController contactController = Get.find<ContactController>();
  final UserController userController = Get.find<UserController>();

  // Loading flags
  RxBool isFetchingContacts = false.obs; // For contact fetching
  RxBool isLoading = false.obs; // For group creation

  RxList<Contact> contacts = <Contact>[].obs;
  RxList<Contact> filteredContacts = <Contact>[].obs;
  RxList<Contact> selectedContacts = <Contact>[].obs;

  final TextEditingController groupNameController = TextEditingController();
  final TextEditingController groupLogoController = TextEditingController();

  @override
  Future<void> onInit() async {
    super.onInit();
    debugPrint('GroupChatController onInit----------------------------');

    await fetchContacts();
    // await contactController.fetchPhoneContacts();
  }

  String removeSubstring(String input) {
    // Trouver l'indice de "+" dans la chaîne
    int plusIndex = input.indexOf("+");

    if (plusIndex == -1) {
      // Si le "+" n'est pas trouvé, renvoyer la chaîne originale
      return input;
    }

    // Trouver l'indice de l'espace après "+"
    int spaceIndex = input.indexOf(" ", plusIndex);

    if (spaceIndex == -1) {
      // Si aucun espace n'est trouvé après "+", on enlève jusqu'à la fin
      return input.substring(0, plusIndex);
    }

    // Créer une nouvelle chaîne sans la partie entre "+" et l'espace
    return input.substring(0, plusIndex) + input.substring(spaceIndex);
  }

  String normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _fetchContacts() async {
    debugPrint('Fetching contacts create group..........................');
    final token = await userController.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar("Error", "Failed to retrieve token. Please log in again.");
      return;
    }

    try {
      debugPrint('GroupChatController onInit----------------------111------');
      isLoading.value = true;
      //  await contactApiService.getContacts(token);
      await contactController.loadCachedContacts();
      debugPrint('GroupChatController onInit------22222----------------------');
      if (contactController.originalApiContacts.isEmpty) {
        await contactController.fetchContacts(token);
      }
      debugPrint('GroupChatController onInit-----------33-----------------');
      // Fetch phone contacts if not already cached
      if (contactController.originalPhoneContacts.isEmpty) {
        final phoneContacts = await contactController.fetchPhoneContacts();
        contactController.originalPhoneContacts.assignAll(phoneContacts);
      }
      // await contactController.fetchContacts(token);
      // final phoneContacts = await contactController.fetchPhoneContacts();
      // contactController.originalPhoneContacts.assignAll(phoneContacts);
      // // Load cached contacts first
      // await contactController.loadCachedContacts();

      // Fetch API contacts if not already cached
      // if (contactController.originalApiContacts.isEmpty) {
      //   await contactController.fetchContacts(token);
      // }

      // // Fetch phone contacts if not already cached
      // if (contactController.originalPhoneContacts.isEmpty) {
      //   final phoneContacts = await contactController.fetchPhoneContacts();
      //   contactController.originalPhoneContacts.assignAll(phoneContacts);
      // }

      // Update the `isPhoneContact` flag for phone contacts that exist in the API contacts
      for (var phoneContact in contactController.originalPhoneContacts) {
        final normalizedPhoneNumber =
            removeSubstring(phoneContact.phoneNumber!).replaceAll(' ', '');

        // Check if the phone contact exists in the API contact list
        bool existsInApi =
            contactController.originalApiContacts.any((apiContact) {
          debugPrint(
              'Phone contact exists in API: ${apiContact.phoneNumber!.split(' ').last}');
          debugPrint('Phone contact exists : $normalizedPhoneNumber');
          debugPrint(
              'test contact exists : ${normalizePhoneNumber(apiContact.phoneNumber!.split(' ').last) == normalizedPhoneNumber}');
          return normalizePhoneNumber(
                  apiContact.phoneNumber!.split(' ').last) ==
              normalizedPhoneNumber;
        });
        debugPrint('Phone number===========: ${phoneContact.isPhoneContact}');

        // If it exists in the API, set isPhoneContact to false
        if (existsInApi) {
          phoneContact.isPhoneContact = false;
        } else {
          phoneContact.isPhoneContact = true;
        }
        debugPrint('isPhone number===========: ${phoneContact.isPhoneContact}');
      }

      // Combine API and phone contacts, ensuring no duplicates
      final uniquePhoneContacts =
          contactController.originalPhoneContacts.where((phoneContact) {
        debugPrint('Phone number===========: ${phoneContact.phoneNumber}');
        final normalizedPhoneNumber =
            removeSubstring(phoneContact.phoneNumber!).replaceAll(' ', '');

        return !contactController.originalApiContacts.any((apiContact) =>
            apiContact.phoneNumber!.split(' ').last == normalizedPhoneNumber);
      }).toList();

      contactController.contacts.assignAll(
          [...contactController.originalApiContacts, ...uniquePhoneContacts]);
      filteredContacts.value = contacts;
      // Debug logs
      debugPrint(
          'Original API Contacts: ${contactController.originalApiContacts.length}');
      debugPrint(
          'Original Phone Contacts: ${contactController.originalPhoneContacts.length}');
      debugPrint('Unique Phone Contacts: ${uniquePhoneContacts.length}');
      debugPrint('Final Contacts: ${contactController.contacts.length}');
    } catch (e) {
      Get.snackbar('Error', 'Failed to retrieve contacts. Please try again.');
      debugPrint('Error fetching contacts: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchContacts() async {
    isFetchingContacts.value = true; // Start fetching contacts
    try {
      final token = await userController.getToken();
      if (token != null && token.isNotEmpty) {
        await contactController.fetchContacts(token);

        final phoneContacts = await contactController.fetchPhoneContacts();
        contactController.contacts.addAll(phoneContacts);
        contacts.value = contactController.contacts; // Sync contacts
        filteredContacts.value = contacts;
        debugPrint('Contacts fetch in create grp : ${contacts.length}');
      } else {
        Get.snackbar('Error', 'Token is missing.');
      }
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
    } finally {
      isFetchingContacts.value = false; // End fetching contacts
    }
  }

  /// Search Contacts
  void searchContacts(String query) {
    if (query.isEmpty) {
      filteredContacts.value = contacts;
    } else {
      filteredContacts.value = contacts
          .where((contact) =>
              contact.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  /// Upload logo to Cloudinary
  Future<String?> uploadLogoToCloudinary(File image) async {
    try {
      final imageUrl =
          await userController.userApiService.uploadImageToCloudinary(image);
      return imageUrl;
    } catch (e) {
      debugPrint("Failed to upload image: $e");
      return null;
    }
  }

  /// Toggle Contact Selection
  void toggleSelection(Contact contact) {
    if (selectedContacts.contains(contact)) {
      selectedContacts.remove(contact);
    } else {
      selectedContacts.add(contact);
    }
  }

  /// Create Group Chat
  Future<void> createGroupChat(BuildContext context, param1, {String? logoUrl}) async {
    final token = await userController.getToken();
    if (token == null || token.isEmpty) {
      Get.snackbar("Error".tr, "token_error".tr);
      Get.toNamed(Routes.login);
      return;
    }

    final memberIds = selectedContacts.map((contact) => contact.id).toList();
    final groupName = groupNameController.text.trim();
    final groupLogo = groupLogoController.text.trim();

    if (groupName.isEmpty) {
      Get.snackbar("Error".tr, "please_provide_a_group_name.".tr);
      return;
    }

    isLoading.value = true; // Start group creation loading
    try {
      final isGroupCreate =
          await conversationController.createGroupConversation(
        context: context,
        token: token,
        name: groupName,
        logo: groupLogo.isEmpty ? null : groupLogo,
        memberIds: memberIds,
      );

      if (isGroupCreate) {
        final newGroup = conversationController.conversations.last;
        Get.to(() => ChatRoomPage(
              name: newGroup.name ?? 'Group Chat',
              phoneNumber: '', // Not applicable for groups
              avatarUrl: newGroup.logo,
              conversationId: newGroup.id,
              createdAt: newGroup.createdAt,
            ));
      }
    } catch (e) {
      debugPrint('Error creating group=============: $e');
      // showCustomDialogVertical(context, "Nidhal", () {});
      // Get.snackbar('Error', 'Failed to create group.');
    } finally {
      isLoading.value = false; // End group creation loading
    }
  }
}
