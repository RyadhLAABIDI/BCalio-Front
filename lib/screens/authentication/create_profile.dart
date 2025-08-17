import 'package:bcalio/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/user_controller.dart';
import '../../utils/misc.dart';
import '../../widgets/base_widget/input_field.dart';
import '../../widgets/base_widget/otp_loading_indicator.dart';
import '../../widgets/base_widget/primary_button.dart';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final UserController userController = Get.find<UserController>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  RxBool isPasswordVisible = false.obs;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Obx(() {
      final isLoading = userController.isLoading.value;
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Create Profile'.tr,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? theme.colorScheme.onSurface : Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [kDarkBgColor, kDarkBgColor.withOpacity(0.8)]
                  : [kLightPrimaryColor.withOpacity(0.9), kLightBgColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            "Fill in the details below to create your profile.".tr,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().fadeIn(duration: 800.ms),
                        const SizedBox(height: 40),
                        StyledInputField(
                          controller: nameController,
                          label: 'Name'.tr,
                          hint: 'Enter your name'.tr,
                          imagePath: "assets/3d_icons/user_icon.png",
                        ).animate().fadeIn(duration: 1000.ms, delay: 200.ms),
                        const SizedBox(height: 20),
                        StyledInputField(
                          controller: emailController,
                          label: 'Email'.tr,
                          hint: 'Enter your email'.tr,
                          imagePath: "assets/3d_icons/email_icon.png",
                          inputType: TextInputType.emailAddress,
                        ).animate().fadeIn(duration: 1200.ms, delay: 400.ms),
                        const SizedBox(height: 20),
                        StyledInputField(
                          controller: passwordController,
                          label: 'Password'.tr,
                          hint: 'Enter your password'.tr,
                          imagePath: "assets/3d_icons/password_icon.png",
                          inputType: TextInputType.visiblePassword,
                          trailing: Obx(
                            () => IconButton(
                              icon: Icon(
                                isPasswordVisible.value ? Iconsax.eye : Iconsax.eye_slash,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                isPasswordVisible.value = !isPasswordVisible.value;
                              },
                            ),
                          ),
                          obscureText: !isPasswordVisible.value,
                        ).animate().fadeIn(duration: 1400.ms, delay: 600.ms),
                        const SizedBox(height: 40),
                        PrimaryButton(
                          title: 'Create Profile'.tr,
                          onPressed: _finishProfileCreation,
                        ).animate().fadeIn(duration: 1600.ms, delay: 800.ms),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            "By creating a profile, you agree to our Terms & Conditions.".tr,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ).animate().fadeIn(duration: 1800.ms, delay: 1000.ms),
                      ],
                    ),
                  ),
                ),
              ),
              if (isLoading) const OtpLoadingIndicator(),
            ],
          ),
        ),
      );
    });
  }

  void _finishProfileCreation() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phoneNumber = Get.arguments['phoneNumber'];

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showSnackbar("Please fill all fields".tr);
      return;
    }

    await userController.registerWithAvatar(
      email: email,
      password: password,
      name: name,
      phoneNumber: phoneNumber,
    );

    if (userController.currentUser.value != null) {
      Get.offAllNamed('/login');
    }
  }
}