import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a success snackbar with a green background.
void showSuccessSnackbar(String message) {
  Get.snackbar(
    "Success".tr,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.green.shade600,
    colorText: Colors.white,
    borderRadius: 12,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
    icon: const Icon(Icons.check_circle, color: Colors.white),
    snackStyle: SnackStyle.FLOATING,
  );
}

/// Shows an error snackbar with a red background.
void showErrorSnackbar(String message) {
  Get.snackbar(
    "Error".tr,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red.shade600,
    colorText: Colors.white,
    borderRadius: 12,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
    icon: const Icon(Icons.error, color: Colors.white),
    snackStyle: SnackStyle.FLOATING,
  );
}
