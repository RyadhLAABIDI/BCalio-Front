import 'package:bcalio/controllers/theme_controller.dart';
import 'package:bcalio/utils/misc.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:zego_uikit/zego_uikit.dart'; // Pour ZegoUIKitUser et ButtonIcon
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../utils/zegocloud_constants.dart';

class CallServiceController extends GetxController {
  void initializeCallService(String userID, String userName) {
    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoCloudConstants.appID,
      appSign: ZegoCloudConstants.appSign,
      userID: userID,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
    );
  }

  void deinitializeCallService() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
  }

  Widget getCallInvitationButton({
    required String targetUserID,
    required String targetUserName,
    required bool isVideoCall,
  }) {
    return ZegoSendCallInvitationButton(
      isVideoCall: isVideoCall,
      resourceID: "zegouikit_call",
      invitees: [ZegoUIKitUser(id: targetUserID, name: targetUserName)], // Arguments nommés
      buttonSize: const Size(40, 40),
      icon: ButtonIcon(
        icon: Padding(
          padding: const EdgeInsets.only(right: 15),
          child: isVideoCall
              ? const Icon(Icons.video_call, size: 30, color: Colors.white)
              : const Icon(Icons.phone, size: 30, color: Colors.white),
        ),
      ),
      iconSize: const Size(30, 30),
      text: '',
      clickableBackgroundColor: Colors.transparent,
      unclickableBackgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      borderRadius: 0,
      onPressed: (code, message, errorInvitees) async {
        print(
            'Call invitation result - Code: $code, Message: $message, Error Invitees: $errorInvitees');

        // Handle null or invalid code
        final parsedCode = int.tryParse(code ?? '');
        if (parsedCode == null) {
          return;
        }

        // Handle specific error codes
        switch (parsedCode) {
          case -1: // Liste d'invités vide
            _showErrorPopup(
              title: "call_failed".tr,
              message:
                  "No user has been selected for the call. Please check the invitees list."
                      .tr,
            );
            return;

          case 107026: // Utilisateur non enregistré
            _showErrorPopup(
              title: "call_failed".tr,
              message: "The user has not installed the app".tr,
            );
            return;

          case 107027: // Appel déjà en cours
            showSnackbar(
              "Un appel est déjà en cours. Veuillez réessayer plus tard.".tr,
            );
            return;

          default: // Autres erreurs
            _showErrorPopup(
              title: "call_failed".tr,
              message:
                  "une_erreur_inattendue_s_est_produite._veuillez_réessayer."
                      .tr,
            );
        }
      },
    );
  }

  void _showErrorPopup({
    required String title,
    required String message,
    IconData icon = Iconsax.close_circle,
  }) {
    final _themeController = Get.find<ThemeController>();
    final isDarkMode = _themeController.isDarkMode;
    Get.dialog(
      AlertDialog(
        backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                )),
          ),
        ],
      ),
    );
  }
}