// import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/misc.dart';
import '../widgets/base_widget/custom_snack_bar.dart';

class AddContactController extends GetxController {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  final isLoading = false.obs;

  /// Requests contact permission
  Future<void> requestPermission() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      showSnackbar(
          "Permission Denied, Contact permission is required to add a contact"
              .tr);
      throw Exception("Permission denied");
    }
  }

  /// Validates the input fields
  bool validateFields() {
    if (nameController.text.trim().isEmpty) {
      showErrorSnackbar("Name is required.".tr);
      return false;
    }

    if (phoneController.text.trim().isEmpty) {
      showErrorSnackbar("Phone number is required.".tr);
      return false;
    }

    if (emailController.text.isNotEmpty &&
        !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailController.text.trim())) {
      showErrorSnackbar("Invalid email address.".tr);
      return false;
    }

    return true;
  }

  /// Adds a new contact
  Future<void> addContact() async {
    if (!validateFields()) return;

    isLoading.value = true;

    try {
      // Request permission
      await requestPermission();

      // Create the contact
      final contact = Contact(
        displayName: nameController.text.trim(),
        phones: [
          Phone(phoneController.text.trim(), label: PhoneLabel.mobile),
        ],
        emails: emailController.text.isNotEmpty
            ? [
                Email(
                  emailController.text.trim(),
                  label: EmailLabel.work,
                ),
              ]
            : [],
      );

      // Add contact to phonebook
      await FlutterContacts.insertContact(contact);

      // Show success message and redirect
      showSuccessSnackbar("Contact added successfully!".tr);
      Get.offNamed('/allContactsScreen');
    } catch (e) {
      // Handle errors
      showErrorSnackbar("Failed to add contact,Please try again!".tr);
    } finally {
      isLoading.value = false;
    }
  }
}