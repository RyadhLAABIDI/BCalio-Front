import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Should only be used in places where we can assume
// that the user is logged in.

void showSnackbar(String message) {
  Get.snackbar(
    "Notice".tr,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.black87,
    colorText: Colors.white,
    borderRadius: 12,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
    icon: const Icon(Icons.info, color: Colors.white),
    snackStyle: SnackStyle.FLOATING,
  );
}

String removePhoneDecoration(String phone) {
  return phone
      .replaceAll(' ', '')
      .replaceAll('(', '')
      .replaceAll(')', '')
      .replaceAll('-', '');
}

const String baseUrl = "https://app.b-callio.com/api";
const String cloudName = 'bkalio';
const String uploadPreset = 'telegram_preset';
// Node (QR)
const String qrNodeUrl = 'https://backendcall.b-callio.com';

// API “pairing” (ton serveur local avec /api/pair/*)
const String pairBaseUrl = 'https://backendcall.b-callio.com';

// Serveur pair/sync local (même que pushBaseUrl de UserController)
const String callServerBase = 'https://backendcall.b-callio.com';



