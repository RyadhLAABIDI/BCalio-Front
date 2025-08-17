import 'dart:developer';
import 'dart:io';

import 'package:bcalio/utils/shared_preferens_helper.dart';
import 'package:bcalio/widgets/base_widget/custom_snack_bar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:permission_handler/permission_handler.dart';

class PermissionService extends GetxService {
  Future<bool> requestCameraPermission() async {
    bool hasRequested =
        await SharedPreferensHelper.getHasRequestedCameraPermission();
    PermissionStatus status = PermissionStatus.denied;
    if (!hasRequested) {
      await Permission.camera.onDeniedCallback(() {
        status = PermissionStatus.denied;
        SharedPreferensHelper.saveHasRequestedCameraPermission(false);
      }).onGrantedCallback(() {
        status = PermissionStatus.granted;
        SharedPreferensHelper.saveHasRequestedCameraPermission(true);
      }).request();
    }
    SharedPreferensHelper.saveHasRequestedCameraPermission(false);

    return status == PermissionStatus.granted;
  }

  Future<bool> requestStoragePermission() async {
    bool hasRequested =
        await SharedPreferensHelper.readHasRequestedStoragePermission();
    PermissionStatus status = PermissionStatus.denied;

    if (!hasRequested) {
      if (Platform.isIOS) {
        await Permission.photos.onDeniedCallback(() {
          status = PermissionStatus.denied;
          SharedPreferensHelper.saveHasRequestedStoragePermission(false);
        }).onGrantedCallback(() {
          status = PermissionStatus.granted;
          SharedPreferensHelper.saveHasRequestedStoragePermission(true);
        }).request();
      } else if (Platform.isAndroid) {
        await Permission.storage.onDeniedCallback(() {
          status = PermissionStatus.denied;
        }).onGrantedCallback(() {
          status = PermissionStatus.granted;
          SharedPreferensHelper.saveHasRequestedStoragePermission(true);
        }).request();
      }
    }
    SharedPreferensHelper.saveHasRequestedStoragePermission(false);
    return status == PermissionStatus.granted;
  }

  Future<bool> requestMicrophonePermission() async {
    bool hasRequested =
        await SharedPreferensHelper.getHasRequestedMicrophonePermission();
    PermissionStatus status = PermissionStatus.denied;

    if (!hasRequested) {
      await Permission.microphone.onDeniedCallback(() {
        status = PermissionStatus.denied;
        SharedPreferensHelper.saveHasRequestedMicrophonePermission(false);
      }).onGrantedCallback(() {
        status = PermissionStatus.granted;
        SharedPreferensHelper.saveHasRequestedMicrophonePermission(true);
      }).request();
    }

    SharedPreferensHelper.saveHasRequestedMicrophonePermission(false);

    return status == PermissionStatus.granted;
  }

  // Future<bool> requestNotificationPermission() async {
  //   FirebaseMessaging messaging = FirebaseMessaging.instance;

  //   bool hasRequested =
  //       await SharedPreferensHelper.readHasRequestedStoragePermission() ;

  //   if (!hasRequested) {
  //     NotificationSettings settings = await messaging.requestPermission(
  //       alert: true,
  //       announcement: false,
  //       badge: true,
  //       carPlay: false,
  //       criticalAlert: false,
  //       provisional: false,
  //       sound: true,
  //     );

  //     await SharedPreferensHelper.saveHasRequestedNotificationPermission(true);

  //     if (settings.authorizationStatus == AuthorizationStatus.authorized) {
  //       log("Notification permission granted");
  //       return true;
  //     } else {
  //       log("Notification permission denied");
  //       return false;
  //     }
  //   } else {
  //     NotificationSettings currentSettings =
  //         await messaging.getNotificationSettings();
  //     return currentSettings.authorizationStatus ==
  //         AuthorizationStatus.authorized;
  //   }
  // }

  void checkServiceStatus(String message) async {
    showErrorSnackbar(message);
  }
}
