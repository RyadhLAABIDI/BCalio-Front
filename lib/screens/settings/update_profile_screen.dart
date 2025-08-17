import 'dart:io';
import 'package:bcalio/widgets/base_widget/custom_snack_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/user_controller.dart';
import '../../themes/theme.dart';
import '../../widgets/base_widget/input_field.dart';
import '../../widgets/base_widget/primary_button.dart';
import '../../widgets/base_widget/otp_loading_indicator.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final UserController userController = Get.find<UserController>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController aboutController = TextEditingController();
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    // Pre-fill the fields with the current user's data
    final user = userController.currentUser.value;
    nameController.text = user?.name ?? '';
    aboutController.text = user?.about ?? '';
  }

  final ImagePicker picker = ImagePicker();

  Future<void> getImageFromGallery(BuildContext context) async {
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      debugPrint('Image path from gallery: ${image?.path}');
      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
      Navigator.pop(context); // Ferme le bottom sheet
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      // Vérifier si l'erreur est liée à une permission refusée
      final permissionStatus = await Permission.photos.status;
      if (permissionStatus.isPermanentlyDenied) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("permission_requise".tr),
            content: Text(
                "Vous devez autoriser l'accès à la galerie dans les paramètres de l'application.".tr),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("cancel".tr),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings(); // Ouvre les paramètres de l'application
                },
                child: Text("Ouvrir les paramètres".tr),
              ),
            ],
          ),
        );
      } else {
        showErrorSnackbar("Échec de l'accès à la galerie : $e".tr);
      }
    }
  }

  Future<void> getImageFromCamera(BuildContext context) async {
    // Vérifier et demander la permission pour accéder à la caméra
    final permissionStatus = await Permission.camera.request();
    debugPrint('Permission camera status: $permissionStatus');
    
    if (permissionStatus.isGranted) {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      debugPrint('Image path from camera: ${image?.path}');
      if (image != null) {
        setState(() {
          selectedImage = File(image.path);
        });
      }
      Navigator.pop(context); // Ferme le bottom sheet
    } else if (permissionStatus.isPermanentlyDenied) {
      // Si la permission est définitivement refusée, afficher un dialogue
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("permission_requise".tr),
          content: Text(
              "Vous devez autoriser l'accès à la caméra dans les paramètres de l'application.".tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("cancel".tr),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings(); // Ouvre les paramètres de l'application
              },
              child: Text("Ouvrir les paramètres".tr),
            ),
          ],
        ),
      );
    } else {
      // Si la permission est refusée (mais pas définitivement), afficher un message
      showErrorSnackbar("Permission d'accès à la caméra refusée.".tr);
    }
  }

  getImage(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text("gallery".tr),
            onPressed: () {
              getImageFromGallery(context);
            },
          ),
          CupertinoActionSheetAction(
            child: Text("camera".tr),
            onPressed: () {
              getImageFromCamera(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text("cancel".tr),
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    final name = nameController.text.trim();
    final about = aboutController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final fcmToken = prefs.getString('fcmToken') ?? '';
    final latitude = prefs.getDouble('latitude') ?? 0.0;
    final longitude = prefs.getDouble('longitude') ?? 0.0;
    // Handle optional image upload
    String? imageUrl;
    if (selectedImage != null) {
      imageUrl = await userController.userApiService
          .uploadImageToCloudinary(selectedImage!);
    } else {
      imageUrl =
          userController.currentUser.value?.image; // Keep the current image
    }

    // Call the update profile method
    await userController.updateProfile(
      name:
          name.isNotEmpty ? name : userController.currentUser.value?.name ?? '',
      image: imageUrl ?? '',
      about: about.isNotEmpty
          ? about
          : userController.currentUser.value?.about ?? '',
      geolocalisation: latitude.toString(),
      screenshotToken: longitude.toString(),
      rfcToken: fcmToken,
    );

    // Navigate back to the previous screen
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Obx(() {
      final isLoading = userController.isLoading.value;

      return Stack(
        children: [
          Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              flexibleSpace: Container(
                color: isDarkMode ? kDarkBgColor : kLightPrimaryColor,
              ),
              elevation: 0,
              title: Text(
                'Update Profile'.tr,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isDarkMode ? Colors.white : kDarkBgColor,
                ),
              ),
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Iconsax.arrow_left,
                  color: isDarkMode ? Colors.white : kDarkBgColor,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Profile Picture
                      Center(
                        child: GestureDetector(
                          onTap: () => getImage(context),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundImage: selectedImage != null
                                    ? FileImage(selectedImage!)
                                    : userController.currentUser.value?.image !=
                                            null
                                        ? NetworkImage(userController
                                            .currentUser.value!.image!)
                                        : null,
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                child: selectedImage == null &&
                                        userController
                                                .currentUser.value?.image ==
                                            null
                                    ? Icon(
                                        Iconsax.user,
                                        size: 50,
                                        color: theme.colorScheme.primary,
                                      )
                                    : null,
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    theme.appBarTheme.backgroundColor,
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Instruction Text
                      Center(
                        child: Text(
                          "Update your profile details below.".tr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Name Input
                      StyledInputField(
                        controller: nameController,
                        label: 'Name'.tr,
                        hint: 'Enter your name'.tr,
                        imagePath: "assets/3d_icons/user_icon.png",
                      ),
                      const SizedBox(height: 20),
                      /*
                      // About Input
                      StyledInputField(
                        controller: aboutController,
                        label: 'About'.tr,
                        hint: 'Tell us about yourself'.tr,
                        imagePath: "assets/3d_icons/about_icon.png",
                      ),*/
                      const SizedBox(height: 40),

                      // Update Button
                      PrimaryButton(
                        title: 'Update Profile'.tr,
                        onPressed: _updateProfile,
                      ),

                      const SizedBox(height: 20),

                      // Additional Note
                      Center(
                        child: Text(
                          "Changes will be reflected immediately.".tr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isLoading) const OtpLoadingIndicator(),
        ],
      );
    });
  }
}