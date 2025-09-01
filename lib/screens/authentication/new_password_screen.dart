import 'package:bcalio/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // visibilité des mots de passe
  final RxBool isPasswordVisible = false.obs;
  final RxBool isConfirmPasswordVisible = false.obs;

  bool _submitting = false;

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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [kDarkBgColor, kDarkBgColor.withOpacity(0.8)]
                    : [kLightPrimaryColor.withOpacity(0.3), kLightBgColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
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

                      // ========= Nouveau mot de passe =========
                      Obx(() => StyledInputField(
                            controller: passwordController,
                            label: "new_password".tr,
                            hint: "enter_new_password".tr,
                            imagePath: "assets/3d_icons/password_icon.png",
                            inputType: TextInputType.visiblePassword,
                            trailing: IconButton(
                              icon: Icon(
                                isPasswordVisible.value ? Iconsax.eye : Iconsax.eye_slash,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                isPasswordVisible.toggle();
                                debugPrint('[NewPassword] toggle eye main -> ${isPasswordVisible.value}');
                              },
                            ),
                            obscureText: !isPasswordVisible.value,
                          ).animate().fadeIn(duration: 1000.ms, delay: 200.ms)),

                      const SizedBox(height: 20),

                      // ========= Confirmation =========
                      Obx(() => StyledInputField(
                            controller: confirmPasswordController,
                            label: "confirm_password".tr,
                            hint: "Re-enter_your_new_password".tr,
                            imagePath: "assets/3d_icons/password_icon.png",
                            inputType: TextInputType.visiblePassword,
                            trailing: IconButton(
                              icon: Icon(
                                isConfirmPasswordVisible.value ? Iconsax.eye : Iconsax.eye_slash,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                isConfirmPasswordVisible.toggle();
                                debugPrint('[NewPassword] toggle eye confirm -> ${isConfirmPasswordVisible.value}');
                              },
                            ),
                            obscureText: !isConfirmPasswordVisible.value,
                          ).animate().fadeIn(duration: 1200.ms, delay: 400.ms)),

                      const SizedBox(height: 40),

                      PrimaryButton(
                        title: _submitting ? '...' : 'Update'.tr,
                        onPressed: _submitting
                            ? null
                            : () {
                                debugPrint('[NewPassword] Bouton Update pressé — _submitting=$_submitting');
                                _validateAndSubmit();
                              },
                      ).animate().fadeIn(duration: 1400.ms, delay: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_submitting) const OtpLoadingIndicator(),
        ],
      ),
    );
  }

  void _validateAndSubmit() async {
    debugPrint('[NewPassword] _validateAndSubmit() lancé');

    final password = passwordController.text.trim();
    final confirm  = confirmPasswordController.text.trim();

    debugPrint('[NewPassword] password.length=${password.length}, confirm.length=${confirm.length}');

    if (password.isEmpty || confirm.isEmpty) {
      showSnackbar("please_fill_all_fields".tr);
      return;
    }

    // Aligne-toi sur l’API : longueur ≥ 8 suffit
    final strong = _isValidPassword(password);
    debugPrint('[NewPassword] validation: strong=$strong');
    if (!strong) {
      showSnackbar("Password_must_be_at_least_8_characters_long".tr);
      return;
    }

    if (password != confirm) {
      showSnackbar("passwords_do_not_match".tr);
      return;
    }

    await _updatePassword(password);
  }

  bool _isValidPassword(String pwd) {
    final lenOK = pwd.length >= 8;
    debugPrint('[NewPassword] rule len>=8 -> $lenOK');
    return lenOK;
  }

  Future<void> _updatePassword(String newPassword) async {
    setState(() => _submitting = true);
    debugPrint('[NewPassword] _updatePassword() START');
    debugPrint('[NewPassword] _submitting=true');

    final prefs = await SharedPreferences.getInstance();
    String? rawPhone = prefs.getString("phoneNumber");
    debugPrint('[NewPassword] phoneNumber depuis prefs = $rawPhone');

    if (rawPhone == null || rawPhone.trim().isEmpty) {
      setState(() => _submitting = false);
      showSnackbar("Erreur: numéro introuvable. Recommencez la procédure.".tr);
      return;
    }

    // Génère des formats candidats (inclut la variante AVEC espace)
    List<String> _candidatesFrom(String p) {
      final trimmed = p.trim();
      final e164NoSpace = trimmed.replaceAll(' ', '');
      final digits      = e164NoSpace.replaceAll(RegExp(r'[^\d]'), '');

      // Variante E.164 AVEC espace : "+CCC NNNNNNNN"
      String e164Space = trimmed;
      final m = RegExp(r'^\+(\d{1,3})(\d{4,})$').firstMatch(e164NoSpace);
      if (m != null) {
        e164Space = '+${m.group(1)} ${m.group(2)}';
      }

      // Local Tunisie
      String local = digits;
      if (digits.startsWith('216') && digits.length >= 11) {
        local = digits.substring(3);
      }
      final local0 = local.startsWith('0') ? local : '0$local';
      final intl00 = digits.startsWith('00') ? digits : '00$digits';

      final uniq = <String>{};
      for (final s in <String>[e164Space, trimmed, e164NoSpace, digits, local, local0, intl00]) {
        if (s.isNotEmpty) uniq.add(s);
      }
      final list = uniq.toList();
      debugPrint('[NewPassword] candidats téléphone = $list');
      return list;
    }

    final candidates = _candidatesFrom(rawPhone);

    final url = Uri.parse('https://app.b-callio.com/api/forget-password');
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    Future<http.Response> _post(String phone) {
      final body = json.encode({"phoneNumber": phone, "newPassword": newPassword});
      debugPrint('[NewPassword] → POST ${url.toString()}  body=$body');
      return http.post(url, headers: headers, body: body);
    }

    http.Response? lastResp;
    int attempt = 0;
    for (final phone in candidates) {
      attempt++;
      final resp = await _post(phone);
      lastResp = resp;
      debugPrint('[NewPassword] ← RESP #$attempt: ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200) {
        showSnackbar("password_updated_successfully".tr);
        await prefs.remove('phoneNumber');
        if (mounted) {
          setState(() => _submitting = false);
          Get.toNamed('/login');
        }
        return;
      }
      if (resp.statusCode != 404 && resp.statusCode != 400 && resp.statusCode != 422) {
        break;
      }
    }

    debugPrint('[NewPassword] Échec: aucune variante acceptée; last=${lastResp?.statusCode} ${lastResp?.body}');
    if (mounted) {
      setState(() => _submitting = false);
      showSnackbar("error_failed_to_update_password".tr);
    }
  }
}
