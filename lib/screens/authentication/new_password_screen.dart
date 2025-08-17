import 'package:bcalio/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../controllers/user_controller.dart';
import '../../utils/misc.dart';
import '../../widgets/base_widget/input_field.dart';
import '../../widgets/base_widget/otp_loading_indicator.dart';
import '../../widgets/base_widget/primary_button.dart';

class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final UserController userController = Get.find<UserController>();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  RxBool isPasswordVisible = false.obs;
  RxBool isConfirmPasswordVisible = false.obs;

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
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
            "new_password".tr,
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
                  : [kLightPrimaryColor.withOpacity(0.3), kLightBgColor],
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
                        const SizedBox(height: 100),
                        Text(
                          "new_password".tr,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ).animate().fadeIn(duration: 800.ms),
                        const SizedBox(height: 40),
                        StyledInputField(
                          controller: passwordController,
                          label: "new_password".tr,
                          hint: "enter_new_password".tr,
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
                        ).animate().fadeIn(duration: 1000.ms, delay: 200.ms),
                        const SizedBox(height: 20),
                        StyledInputField(
                          controller: confirmPasswordController,
                          label: "confirm_password".tr,
                          hint: "Re-enter_your_new_password".tr,
                          imagePath: "assets/3d_icons/password_icon.png",
                          inputType: TextInputType.visiblePassword,
                          trailing: Obx(
                            () => IconButton(
                              icon: Icon(
                                isConfirmPasswordVisible.value ? Iconsax.eye : Iconsax.eye_slash,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
                              },
                            ),
                          ),
                          obscureText: !isConfirmPasswordVisible.value,
                        ).animate().fadeIn(duration: 1200.ms, delay: 400.ms),
                        const SizedBox(height: 40),
                        PrimaryButton(
                          title: 'Update'.tr,
                          onPressed: _validateAndSubmit,
                        ).animate().fadeIn(duration: 1400.ms, delay: 600.ms),
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

  void _validateAndSubmit() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      showSnackbar("please_fill_all_fields".tr);
      return;
    }

    if (!_isValidPassword(password)) {
      showSnackbar(
          "Password_must_be_at_least_8_characters_long_and_contain_uppercase_lowercase_letters_and_numbers".tr);
      return;
    }

    if (password != confirmPassword) {
      showSnackbar("passwords_do_not_match".tr);
      return;
    }

    await _updatePassword(password);
  }

  bool _isValidPassword(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[A-Za-z\d]{8,}$');
    return regex.hasMatch(password);
  }

  Future<void> _updatePassword(String newPassword) async {
    final url = Uri.parse('https://app.b-callio.com/api/forget-password');
    final headers = {'Content-Type': 'application/json'};
    final prefs = await SharedPreferences.getInstance();
    final body = json.encode({
      "phoneNumber": prefs.getString("phoneNumber"),
      "newPassword": newPassword,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        showSnackbar("password_updated_successfully".tr);
        Get.toNamed('/login');
      } else {
        showSnackbar("error_failed_to_update_password".tr);
      }
    } catch (e) {
      showSnackbar("error_failed_to_update_password".tr);
    }
  }
}